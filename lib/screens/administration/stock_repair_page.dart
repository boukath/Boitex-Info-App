// lib/screens/administration/stock_repair_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StockRepairPage extends StatefulWidget {
  const StockRepairPage({super.key});

  @override
  State<StockRepairPage> createState() => _StockRepairPageState();
}

class _StockRepairPageState extends State<StockRepairPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Console Logs
  final List<String> _logs = [];
  bool _isRunning = false;
  double _progress = 0.0;

  void _addLog(String message) {
    setState(() {
      _logs.insert(0, message); // Add to top
    });
  }

  // ===========================================================================
  // 🛠️ THE REPAIR LOGIC (OPTION A: REVERSE REPLAY)
  // ===========================================================================
  Future<void> _startRepair() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
      _progress = 0.0;
    });

    try {
      _addLog("🚀 Starting Repair Sequence...");

      // 1. Fetch ALL Products (The "Truth" Source)
      _addLog("📦 Fetching Product Catalog...");
      final productSnapshot = await _db.collection('produits').get();
      final totalProducts = productSnapshot.docs.length;

      _addLog("✅ Found $totalProducts products. Analyzing history...");

      int processedCount = 0;

      for (var productDoc in productSnapshot.docs) {
        final productId = productDoc.id;
        final productData = productDoc.data();

        // A. Get Current Reality (Handling Safe Types)
        final String productRef = productData['reference'] ?? 'N/A';
        // ✅ FIX: Cast as num, then toInt() to handle doubles like 5.0
        final int currentActualStock = (productData['quantiteEnStock'] as num? ?? 0).toInt();
        final String productName = productData['nom'] ?? 'Produit Inconnu';

        // B. Get History (Newest First)
        final historySnapshot = await _db.collection('stock_movements')
            .where('productId', isEqualTo: productId)
            .orderBy('timestamp', descending: true)
            .get();

        if (historySnapshot.docs.isEmpty) {
          processedCount++;
          setState(() => _progress = processedCount / totalProducts);
          continue; // No history to fix
        }

        // C. REVERSE REPLAY MATH
        // We start with the stock we have RIGHT NOW.
        int runningStockSimulator = currentActualStock;

        final batch = _db.batch();
        bool batchHasData = false;

        for (var moveDoc in historySnapshot.docs) {
          final moveData = moveDoc.data();

          // ✅ FIX: Cast as num, then toInt() to prevent crash on double
          final int change = (moveData['quantityChange'] as num? ?? 0).toInt();

          // LOGIC:
          // The "New Quantity" for this record MUST be what the stock was *at that moment*.
          final int calculatedNewQty = runningStockSimulator;

          // The "Old Quantity" was whatever it was BEFORE this change.
          // Formula: Old = New - Change
          final int calculatedOldQty = calculatedNewQty - change;

          // D. DETECTIVE WORK (Fix Missing Users)
          String? fixedUser = moveData['user'];
          final String notes = moveData['notes'] ?? '';

          // If User is "Inconnu" or missing, look in the notes
          if ((fixedUser == null || fixedUser == 'Inconnu' || fixedUser == 'Technicien') &&
              notes.contains("(Livré)")) {
            try {
              // Extract "Boubaaya" from "...(Livré) Boubaaya"
              final parts = notes.split("(Livré)");
              if (parts.length > 1) {
                fixedUser = parts.last.trim();
                _addLog("🕵️ Found user '$fixedUser' in notes for $productName");
              }
            } catch (e) {
              // Ignore parsing errors
            }
          }

          // E. PREPARE UPDATE
          Map<String, dynamic> updates = {};

          if (moveData['productRef'] == null || moveData['productRef'] == 'N/A') {
            updates['productRef'] = productRef;
          }

          // Always overwrite quantities with the calculated "Truth"
          updates['oldQuantity'] = calculatedOldQty;
          updates['newQuantity'] = calculatedNewQty;

          if (fixedUser != null && fixedUser != moveData['user']) {
            updates['user'] = fixedUser;
          }

          if (updates.isNotEmpty) {
            batch.update(moveDoc.reference, updates);
            batchHasData = true;
          }

          // F. STEP BACK IN TIME
          // For the *next* oldest record, the "New Quantity" will be this record's "Old Quantity"
          runningStockSimulator = calculatedOldQty;
        }

        // Commit updates for this product
        if (batchHasData) {
          await batch.commit();
          _addLog("🛠️ Fixed history for: $productName");
        }

        processedCount++;
        setState(() => _progress = processedCount / totalProducts);
      }

      _addLog("🎉 REPAIR COMPLETED SUCCESSFULLY!");
      _addLog("You can now delete this page.");

    } catch (e) {
      _addLog("❌ ERROR: $e");
    } finally {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("🔧 SYSTEM REPAIR TOOL (Option A)"),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.2),
                border: Border.all(color: Colors.red),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Text(
                    "⚠️ WARNING",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "This script will REWRITE your history logs (stock_movements).\n"
                        "It uses 'Reverse Replay' logic based on your CURRENT stock.\n"
                        "It does NOT change your physical inventory counts.\n\n"
                        "Do not run this if other users are active.",
                    style: TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            if (_isRunning)
              LinearProgressIndicator(value: _progress, color: Colors.red),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.build_circle),
                label: Text(_isRunning ? "REPAIRING... (FIXING DOUBLES) ($_progress%)" : "START REPAIR SEQUENCE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRunning ? Colors.grey : Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isRunning ? null : _startRepair,
              ),
            ),

            const SizedBox(height: 20),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),
            const Text("CONSOLE LOGS:", style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        "> ${_logs[index]}",
                        style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier', fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
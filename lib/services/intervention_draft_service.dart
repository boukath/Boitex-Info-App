import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // ✅ Added this import for VoidCallback
import 'package:path_provider/path_provider.dart';

/// ------------------------------------------------------------------
/// 🛠️ DEBOUNCER
/// A Pro tool to prevent saving on every single keystroke.
/// It waits for the user to STOP typing for [milliseconds] before running.
/// ------------------------------------------------------------------
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

/// ------------------------------------------------------------------
/// 💾 INTERVENTION DRAFT SERVICE
/// Handles saving/loading drafts from the device file system.
/// ------------------------------------------------------------------
class InterventionDraftService {
  // Singleton pattern for easy access (Pro pattern for Services)
  static final InterventionDraftService _instance = InterventionDraftService._internal();
  factory InterventionDraftService() => _instance;
  InterventionDraftService._internal();

  /// Save a draft to the local file system
  /// Returns the file path where it was saved
  Future<String> saveDraft({
    required String interventionId,
    required Map<String, dynamic> formData,
  }) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/draft_intervention_$interventionId.json');

      // Add a timestamp so we know how old this draft is
      final dataToSave = {
        ...formData,
        'draft_saved_at': DateTime.now().toIso8601String(),
        'interventionId': interventionId,
      };

      await file.writeAsString(json.encode(dataToSave));
      // print("✅ Draft saved locally for $interventionId");
      return file.path;
    } catch (e) {
      debugPrint("❌ Error saving draft: $e");
      rethrow;
    }
  }

  /// Retrieve a draft if it exists
  Future<Map<String, dynamic>?> getDraft(String interventionId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/draft_intervention_$interventionId.json');

      if (await file.exists()) {
        final contents = await file.readAsString();
        final data = json.decode(contents) as Map<String, dynamic>;
        debugPrint("📂 Draft loaded for $interventionId (Saved: ${data['draft_saved_at']})");
        return data;
      }
    } catch (e) {
      debugPrint("⚠️ Error reading draft: $e");
    }
    return null;
  }

  /// Delete the draft (Call this after successful submission to server)
  Future<void> clearDraft(String interventionId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/draft_intervention_$interventionId.json');

      if (await file.exists()) {
        await file.delete();
        debugPrint("🗑️ Draft cleared for $interventionId");
      }
    } catch (e) {
      debugPrint("⚠️ Error deleting draft: $e");
    }
  }

  /// Check if a draft exists (Useful for showing a 'Resume' UI badge)
  Future<bool> hasDraft(String interventionId) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/draft_intervention_$interventionId.json');
    return file.exists();
  }
}
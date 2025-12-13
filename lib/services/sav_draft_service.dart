// lib/services/sav_draft_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class SavDraft {
  final String id; // ✅ Unique ID
  final DateTime date; // ✅ Date saved
  final String? clientId;
  final String? clientName; // Helper for the list view
  final String? storeId;
  final String? managerName;
  final String? managerEmail;
  final String ticketType;
  final String creationMode;
  final List<Map<String, String>> items;
  final List<String> mediaPaths;
  final List<String> technicianIds; // ✅ ADD THIS FIELD

  SavDraft({
    required this.id,
    required this.date,
    this.clientId,
    this.clientName,
    this.storeId,
    this.managerName,
    this.managerEmail,
    required this.ticketType,
    required this.creationMode,
    required this.items,
    required this.mediaPaths,
    this.technicianIds = const [], // ✅ Initialize in constructor
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'clientId': clientId,
    'clientName': clientName,
    'storeId': storeId,
    'managerName': managerName,
    'managerEmail': managerEmail,
    'ticketType': ticketType,
    'creationMode': creationMode,
    'items': items,
    'mediaPaths': mediaPaths,
    'technicianIds': technicianIds, // ✅ Save to JSON
  };

  factory SavDraft.fromJson(Map<String, dynamic> json) {
    return SavDraft(
      id: json['id'] ?? const Uuid().v4(),
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      clientId: json['clientId'],
      clientName: json['clientName'],
      storeId: json['storeId'],
      managerName: json['managerName'],
      managerEmail: json['managerEmail'],
      ticketType: json['ticketType'] ?? 'standard',
      creationMode: json['creationMode'] ?? 'individual',
      items: List<Map<String, String>>.from(
          (json['items'] ?? []).map((x) => Map<String, String>.from(x))),
      mediaPaths: List<String>.from(json['mediaPaths'] ?? []),
      technicianIds: List<String>.from(json['technicianIds'] ?? []), // ✅ Load from JSON
    );
  }
}

class SavDraftService {
  static const String _fileName = 'sav_drafts_list.json'; // ✅ Changed filename

  Future<String> _getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$_fileName';
  }

  // ✅ GET ALL
  Future<List<SavDraft>> getAllDrafts() async {
    try {
      final path = await _getFilePath();
      final file = File(path);
      if (!await file.exists()) return [];

      final jsonString = await file.readAsString();
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((j) => SavDraft.fromJson(j)).toList();
    } catch (e) {
      print("Error loading drafts: $e");
      return [];
    }
  }

  // ✅ SAVE (Add new or Update existing)
  Future<void> saveDraft(SavDraft draft) async {
    List<SavDraft> drafts = await getAllDrafts();

    // Check if draft with this ID exists
    final index = drafts.indexWhere((d) => d.id == draft.id);
    if (index != -1) {
      drafts[index] = draft; // Update
    } else {
      drafts.add(draft); // Add new
    }

    // Write to file
    final path = await _getFilePath();
    final file = File(path);
    final jsonString = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await file.writeAsString(jsonString);
  }

  // ✅ DELETE
  Future<void> deleteDraft(String id) async {
    List<SavDraft> drafts = await getAllDrafts();
    drafts.removeWhere((d) => d.id == id);

    final path = await _getFilePath();
    final file = File(path);
    final jsonString = jsonEncode(drafts.map((d) => d.toJson()).toList());
    await file.writeAsString(jsonString);
  }
}
// lib/screens/service_technique/sav_drafts_list_page.dart

import 'package:flutter/material.dart';
import 'package:boitex_info_app/services/sav_draft_service.dart';
import 'package:intl/intl.dart';

class SavDraftsListPage extends StatefulWidget {
  const SavDraftsListPage({super.key});

  @override
  State<SavDraftsListPage> createState() => _SavDraftsListPageState();
}

class _SavDraftsListPageState extends State<SavDraftsListPage> {
  final _draftService = SavDraftService();
  List<SavDraft> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    final drafts = await _draftService.getAllDrafts();
    // Sort by newest first
    drafts.sort((a, b) => b.date.compareTo(a.date));
    if (mounted) {
      setState(() {
        _drafts = drafts;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteDraft(String id) async {
    await _draftService.deleteDraft(id);
    _loadDrafts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Brouillons SAV'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aucun brouillon enregistré'),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _drafts.length,
        itemBuilder: (context, index) {
          final draft = _drafts[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                draft.clientName?.isNotEmpty == true
                    ? draft.clientName!
                    : 'Client Inconnu',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    '${draft.items.length} Article(s) • ${DateFormat('dd MMM yyyy à HH:mm').format(draft.date)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  if (draft.managerName?.isNotEmpty == true)
                    Text('Contact: ${draft.managerName}'),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteDraft(draft.id),
              ),
              onTap: () {
                // Return the selected draft to the previous screen
                Navigator.pop(context, draft);
              },
            ),
          );
        },
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:intl/intl.dart'; // For formatting the time

class DailyActivityFeedPage extends StatefulWidget {
  const DailyActivityFeedPage({super.key});

  @override
  State<DailyActivityFeedPage> createState() => _DailyActivityFeedPageState();
}

class _DailyActivityFeedPageState extends State<DailyActivityFeedPage> {
  late DateTime _startOfToday;
  late DateTime _endOfToday;

  @override
  void initState() {
    super.initState();
    _calculateDateRange();
  }

  // 🔽🔽🔽 FONCTION MISE À JOUR 🔽🔽🔽
  void _calculateDateRange() {
    final DateTime now = DateTime.now();

    // Vérifie s'il est avant 7h du matin
    if (now.hour < 7) {
      // Nous sommes "le jour ouvrable" d'HIER
      // Début = 7h00 HIER
      final DateTime yesterday = now.subtract(const Duration(days: 1));
      _startOfToday =
          DateTime(yesterday.year, yesterday.month, yesterday.day, 7, 0, 0);

      // Fin = 7h00 AUJOURD'HUI
      _endOfToday = DateTime(now.year, now.month, now.day, 7, 0, 0);

    } else {
      // Nous sommes "le jour ouvrable" AUJOURD'HUI (il est 7h00 ou plus tard)
      // Début = 7h00 AUJOURD'HUI
      _startOfToday = DateTime(now.year, now.month, now.day, 7, 0, 0);

      // Fin = 7h00 DEMAIN
      _endOfToday = _startOfToday.add(const Duration(days: 1));
    }
  }
  // 🔼🔼🔼 FIN DE LA FONCTION MISE À JOUR 🔼🔼🔼


  /// Helper to get an icon based on the task type
  IconData _getIconForTask(String? taskType) {
    switch (taskType) {
      case 'Intervention':
        return Icons.build_outlined;
      case 'Installation':
        return Icons.foundation_outlined;
      case 'SAV':
        return Icons.headset_mic_outlined;
      case 'Livraison':
        return Icons.local_shipping_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Journal du Service Technique'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // This is our single, powerful query
        stream: FirebaseFirestore.instance
            .collection('activity_log')
            .where('service', isEqualTo: 'technique')
            .where('timestamp', isGreaterThanOrEqualTo: _startOfToday)
            .where('timestamp', isLessThan: _endOfToday)
            .orderBy('timestamp', descending: true) // Newest first
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Aucune activité pour aujourd\'hui (depuis 7h00).',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
              ),
            );
          }

          final events = snapshot.data!.docs;

          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final data = event.data() as Map<String, dynamic>;

              //
              // ⭐️ ----- MODIFICATION 1 ----- ⭐️
              //
              // Use 'storeName' for the title.
              // Fallback to 'taskTitle' if 'storeName' doesn't exist.
              final String title = data['storeName'] ?? data['taskTitle'] ?? 'Événement';

              //
              // ⭐️ ----- MODIFICATION 2 ----- ⭐️
              //
              // Get the original details.
              String details = data['details'] ?? '...';
              // Check if a 'displayName' field exists in the log.
              final String? displayName = data['displayName'];

              // If details start with "Créée par" and displayName exists,
              // replace the details string with the correct name.
              if (details.startsWith('Créée par') && (displayName != null && displayName.isNotEmpty)) {
                details = 'Créée par $displayName';
              }
              //
              // ⭐️ ----- FIN DES MODIFICATIONS ----- ⭐️
              //

              final String taskType = data['taskType'] ?? '';

              // Format the timestamp
              final Timestamp t = data['timestamp'] ?? Timestamp.now();
              final String time = DateFormat('HH:mm').format(t.toDate());

              return TimelineTile(
                alignment: TimelineAlign.manual,
                lineXY: 0.15, // Puts the line 15% from the left
                isFirst: index == 0,
                isLast: index == events.length - 1,
                // --- The Time on the Left ---
                startChild: Center(
                  child: Text(
                    time,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                // --- The Icon in the Middle ---
                indicatorStyle: IndicatorStyle(
                  width: 40,
                  height: 40,
                  indicator: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIconForTask(taskType),
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                // --- The Content on the Right ---
                endChild: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    elevation: 3,
                    margin: const EdgeInsets.all(0),
                    child: ListTile(
                      title: Text(
                        title, // ✅ This will now show the storeName
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(details), // ✅ This will show the corrected name
                      trailing: Text(
                        taskType,
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      onTap: () {
                        // TODO: You can add navigation logic here
                        // final String docId = data['relatedDocId'];
                        // final String collection = data['relatedCollection'];
                        // A- non, naviguez vers la page de détails
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
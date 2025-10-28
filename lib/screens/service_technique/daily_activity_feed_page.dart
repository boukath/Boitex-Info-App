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

  void _calculateDateRange() {
    // Get "now"
    final DateTime now = DateTime.now();

    // Set the start time to 7:00 AM today
    _startOfToday = DateTime(now.year, now.month, now.day, 7, 0, 0);

    // Set the end time to 7:00 AM tomorrow
    // This query will include everything from 7:00:00 AM today
    // up to 6:59:59 AM tomorrow.
    _endOfToday = _startOfToday.add(const Duration(days: 1));
  }

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

              final String title = data['taskTitle'] ?? 'Événement';
              final String details = data['details'] ?? '...';
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
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(details),
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
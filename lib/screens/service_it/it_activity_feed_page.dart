// lib/screens/service_it/it_activity_feed_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:intl/intl.dart'; // Pour le formatage de l'heure

class ItActivityFeedPage extends StatefulWidget {
  const ItActivityFeedPage({super.key});

  @override
  State<ItActivityFeedPage> createState() => _ItActivityFeedPageState();
}

class _ItActivityFeedPageState extends State<ItActivityFeedPage> {
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

  /// Associe un type de tâche à une icône
  IconData _getIconForTask(String? taskType) {
    // Personnalisez ceci pour vos types de tâches IT
    switch (taskType) {
      case 'Evaluation IT':
        return Icons.computer_rounded;
      case 'Support IT':
        return Icons.support_agent_rounded;
      case 'Maintenance IT':
        return Icons.build_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Journal d'activité IT"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: StreamBuilder<QuerySnapshot>(
        //
        // ⭐️ C'EST LA MODIFICATION PRINCIPALE ⭐️
        //
        // Nous filtrons la collection 'activity_log' pour n'inclure que les
        // types de tâches ('taskType') spécifiques au service IT.
        //
        // ❗️ Assurez-vous que ces chaînes ('Evaluation IT', 'Support IT', etc.)
        // correspondent EXACTEMENT à ce que vous enregistrez dans Firestore.
        //
        stream: FirebaseFirestore.instance
            .collection('activity_log')
            .where('timestamp', isGreaterThanOrEqualTo: _startOfToday)
            .where('timestamp', isLessThan: _endOfToday)
            .where('taskType', whereIn: [
          'Evaluation IT',
          'Support IT',
          'Maintenance IT'
        ]) // <-- ✅ FILTRE IT SPÉCIFIQUE
            .orderBy('timestamp', descending: true)
            .snapshots(),
        //
        // ⭐️ FIN DE LA MODIFICATION ⭐️
        //
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
                child: Text("Erreur lors du chargement du flux."));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_note_rounded,
                      size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    "Aucune activité IT aujourd'hui",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Construit la liste de la timeline
          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final String title = data['taskTitle'] ?? 'Titre non disponible'; // ⭐️ MODIFIÉ: 'title' -> 'taskTitle'
              final String details = data['details'] ?? 'Détails non disponibles';
              final String taskType = data['taskType'] ?? 'N/A';
              final Timestamp timestamp =
                  data['timestamp'] ?? Timestamp.now();
              final String time =
              DateFormat('HH:mm').format(timestamp.toDate());
              final IconData icon = _getIconForTask(data['taskType']);

              return TimelineTile(
                alignment: TimelineAlign.manual,
                lineXY: 0.1, // Aligne la ligne sur la gauche
                isFirst: index == 0,
                isLast: index == snapshot.data!.docs.length - 1,

                // --- Le Temps à Gauche ---
                startChild: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      time,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),

                // --- L'Indicateur (Icône) ---
                indicatorStyle: IndicatorStyle(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(8),
                  indicator: CircleAvatar(
                    // Vous pouvez changer la couleur pour le service IT
                    backgroundColor: Colors.blue.shade800,
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                ),

                // --- Le Contenu à Droite ---
                endChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                        // TODO: Logique de navigation si nécessaire
                        // final String docId = data['relatedDocId'] ?? '';
                        // final String collection = data['relatedCollection'] ?? '';
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
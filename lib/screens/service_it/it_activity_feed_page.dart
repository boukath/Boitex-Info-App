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
      case 'Intervention': // ✅ ADDED 'Intervention'
        return Icons.settings_ethernet_rounded; // Or any icon you prefer
      default:
        return Icons.task_alt_rounded;
    }
  }

  // 🌟 NOUVEAU WIDGET POUR LA CARTE (THÉMÉ)
  Widget _buildEventCard(Map data) {
    final String title = data['taskTitle'] ?? 'Titre non disponible';
    final String details = data['details'] ?? 'Détails non disponibles';
    final String taskType = data['taskType'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.only(left: 16.0, bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        // Material 3 theme colors
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
          // Inner shadow simulation
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(-5, -5),
            spreadRadius: -5,
          ),
        ],
        // Subtle gradient for premium vibe
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.surfaceContainerHighest,
            Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task type tag with gradient
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              taskType.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8.0),
          // Title
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4.0),
          // Details
          Text(
            details,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 MODIFIÉ POUR HEURE HORIZONTALE ET LARGÉE
  Widget _buildTime(String time) {
    return Container(
      width: double.infinity, // Full width for horizontal centering
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Subtle background for prominence
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Text(
        time,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700, // Bolder
          fontSize: 20, // Larger
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // 🌟 NOUVEAU POUR ICÔNE THÉMÉE
  Widget _buildIcon(String taskType) {
    return Container(
      decoration: BoxDecoration(
        // Gradient for IT blue theme
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary, // Often blue in themes
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        _getIconForTask(taskType),
        color: Theme.of(context).colorScheme.onPrimary,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Thémé Scaffold
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text("Journal IT"),
        // Material 3 AppBar
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800), // Responsive
          child: StreamBuilder(
            // ⭐️ C'EST LA MODIFICATION PRINCIPALE ⭐️
            // Nous filtrons maintenant par 'service' == 'it',
            // ce qui inclura automatiquement 'Evaluation IT', 'Support IT',
            // et les 'Intervention' que vous venez de corriger.
            // ⭐️ FIN DE LA MODIFICATION ⭐️
            stream: FirebaseFirestore.instance
                .collection('activity_log')
                .where('timestamp', isGreaterThanOrEqualTo: _startOfToday)
                .where('timestamp', isLessThan: _endOfToday)
                .where('service', isEqualTo: 'it') // <-- ✅ THIS IS THE FIX
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Erreur: ${snapshot.error}",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_note_rounded,
                        size: 60,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Aucune activité IT aujourd'hui",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Construit la liste de la timeline
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final String taskType = data['taskType'] ?? 'N/A';
                  // Formatage de l'heure
                  final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
                  final String time = DateFormat('HH:mm').format(timestamp.toDate());

                  return TimelineTile(
                    alignment: TimelineAlign.manual,
                    lineXY: 0.15, // Adjusted for balance
                    isFirst: index == 0,
                    isLast: index == snapshot.data!.docs.length - 1,
                    // Style de ligne subtil
                    beforeLineStyle: LineStyle(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      thickness: 2,
                    ),
                    afterLineStyle: LineStyle(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      thickness: 2,
                    ),
                    // Empty left side (time moved)
                    startChild: const SizedBox(),
                    // Icône thémée
                    indicatorStyle: IndicatorStyle(
                      width: 40,
                      height: 40,
                      indicator: _buildIcon(taskType),
                    ),
                    // Contenu avec temps horizontal au-dessus
                    endChild: InkWell(
                      onTap: () {
                        // TODO: Logique de navigation si nécessaire
                        // final String docId = data['relatedDocId'] ?? '';
                        // final String collection = data['relatedCollection'] ?? '';
                      },
                      borderRadius: BorderRadius.circular(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTime(time),
                          const SizedBox(height: 8.0),
                          _buildEventCard(data),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

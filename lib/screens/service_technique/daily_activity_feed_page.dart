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

  // 🔽🔽🔽 VOS FONCTIONS (INCHANGÉES) 🔽🔽🔽
  void _calculateDateRange() {
    final DateTime now = DateTime.now();
    if (now.hour < 7) {
      final DateTime yesterday = now.subtract(const Duration(days: 1));
      _startOfToday =
          DateTime(yesterday.year, yesterday.month, yesterday.day, 7, 0, 0);
      _endOfToday = DateTime(now.year, now.month, now.day, 7, 0, 0);
    } else {
      _startOfToday = DateTime(now.year, now.month, now.day, 7, 0, 0);
      _endOfToday = _startOfToday.add(const Duration(days: 1));
    }
  }

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

  // 🔼🔼🔼 FIN DE VOS FONCTIONS (INCHANGÉES) 🔼🔼🔼

  // 🌟
  // 🌟 NOUVEAU WIDGET BUILDER POUR LE CONTENU
  // 🌟
  Widget _buildEventCard(Map data) {
    // --- Logique d'extraction de données (inchangée) ---
    final String storeName = data['storeName'] ?? 'Magasin inconnu';
    final String storeLocation = data['storeLocation'] ?? '';
    final String title = storeLocation.isNotEmpty
        ? '$storeName - $storeLocation'
        : storeName;
    String details = data['details'] ?? '...';
    final String? createdBy = data['createdByName'];
    if (details.startsWith('Créée par') &&
        (createdBy != null && createdBy.isNotEmpty)) {
      details = 'Créée par $createdBy';
    }

    final String taskType = data['taskType'] ?? '';
    // --- Fin de la logique d'extraction ---

    // Le nouveau design de la carte
    return Container(
      margin: const EdgeInsets.only(left: 16.0, bottom: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        // Utilise les couleurs du thème Material 3 pour un look moderne
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Tag" pour le type de tâche
          Text(
            taskType.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8.0),
          // Titre (Magasin)
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4.0),
          // Sous-titre (Détails)
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

  // 🌟
  // 🌟 MODIFIÉ WIDGET BUILDER POUR L'HEURE (LARGÉ ET HORIZONTAL)
  // 🌟
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
        style: Theme.of(context).textTheme.titleMedium?.copyWith( // Upgraded for size
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700, // Bolder
          fontSize: 20, // Larger for better visibility
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // 🌟
  // 🌟 NOUVEAU WIDGET BUILDER POUR L'ICÔNE
  // 🌟
  Widget _buildIcon(String taskType) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getIconForTask(taskType),
        color: Theme.of(context).colorScheme.onPrimaryContainer,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Le Scaffold utilise maintenant les couleurs du thème
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Journal du Service Technique'),
        // AppBar propre et moderne
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      // Center + ConstrainedBox pour la responsivité Web
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800), // Largeur max sur le web
          child: StreamBuilder(
            stream: FirebaseFirestore.instance
                .collection('activity_log')
                .where('service', isEqualTo: 'technique')
                .where('timestamp', isGreaterThanOrEqualTo: _startOfToday)
                .where('timestamp', isLessThan: _endOfToday)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    'Aucune activité pour aujourd\'hui (depuis 7h00).',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final events = snapshot.data!.docs;
              return ListView.builder(
                padding:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  final data = event.data() as Map;
                  final String taskType = data['taskType'] ?? '';
                  // Formatage de l'heure (inchangé)
                  final Timestamp t = data['timestamp'] ?? Timestamp.now();
                  final String time = DateFormat('HH:mm').format(t.toDate());

                  return TimelineTile(
                    alignment: TimelineAlign.manual,
                    lineXY: 0.15, // La ligne est à 15% de la gauche
                    isFirst: index == 0,
                    isLast: index == events.length - 1,
                    // Style de ligne subtil
                    beforeLineStyle: LineStyle(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      thickness: 2,
                    ),
                    afterLineStyle: LineStyle(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      thickness: 2,
                    ),
                    // --- L'Heure DÉPLACÉE AU-DESSUS DE LA CARTE (HORIZONTAL) ---
                    startChild: const SizedBox(), // Empty left side
                    // --- L'Icône au Milieu ---
                    indicatorStyle: IndicatorStyle(
                      width: 40,
                      height: 40,
                      indicator: _buildIcon(taskType),
                    ),
                    // --- Le Contenu (Temps + Carte) à Droite ---
                    endChild: InkWell(
                      // Ajout d'un InkWell pour la navigation
                      onTap: () {
                        // TODO: Vous pouvez ajouter la logique de navigation ici
                        // final String docId = data['relatedDocId'];
                        // final String collection = data['relatedCollection'];
                        // Naviguer vers la page de détails...
                      },
                      borderRadius: BorderRadius.circular(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Time now horizontal above the card
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

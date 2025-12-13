import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// **NEW**: Import the Firestore package to recognize the 'Timestamp' type
import 'package:cloud_firestore/cloud_firestore.dart';

class SummarySection extends StatelessWidget {
  final Map<String, dynamic> data;

  const SummarySection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final interventionDate = (data['interventionDate'] as Timestamp).toDate();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Résumé de la Demande', style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        ListTile(
          title: const Text('Client / Magasin'),
          subtitle: Text('${data['clientName']}\n${data['storeName']} - ${data['storeLocation']}'),
        ),
        ListTile(
          title: const Text('Date d\'intervention'),
          subtitle: Text(DateFormat('dd MMMM yyyy', 'fr_FR').format(interventionDate)),
        ),
        ListTile(
          title: const Text('Description du problème'),
          subtitle: Text(data['description']),
          isThreeLine: true,
        ),
      ],
    );
  }
}
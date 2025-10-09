import 'package:flutter/material.dart';

class AnalyticsCard extends StatelessWidget {
  const AnalyticsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2.0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Title
            const Text(
              'Analytiques',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Reusable row for each analytic item
            _buildAnalyticsRow(label: 'Tickets Ouverts', value: '4'),
            const SizedBox(height: 8),
            _buildAnalyticsRow(label: 'Résolus Aujourd\'hui', value: '5'),
            const SizedBox(height: 16),
            // "View All" link
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Voir toutes les sections >',
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Helper widget to create a row with a label and a value
  Widget _buildAnalyticsRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            color: Colors.blue.shade800,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
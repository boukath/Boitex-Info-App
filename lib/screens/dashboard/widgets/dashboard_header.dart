// lib/screens/dashboard/widgets/dashboard_header.dart

import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  final String displayName;
  final VoidCallback? onHistoryTap;
  final bool showMissionButton;

  const DashboardHeader({
    super.key,
    required this.displayName,
    this.onHistoryTap,
    this.showMissionButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bonsoir', style: TextStyle(fontSize: 16)),
            Text(
              displayName,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            if (showMissionButton)
              IconButton(
                icon: const Icon(Icons.assignment_outlined, color: Colors.grey),
                tooltip: 'Missions',
                onPressed: () {},
              ),
            IconButton(
              icon: const Icon(Icons.history, color: Colors.grey),
              tooltip: 'Historique',
              onPressed: onHistoryTap,
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.grey),
              tooltip: 'Paramètres',
              onPressed: () {},
            ),
          ],
        )
      ],
    );
  }
}
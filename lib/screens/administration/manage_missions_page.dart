// lib/screens/administration/manage_missions_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:boitex_info_app/models/mission.dart';
import 'package:boitex_info_app/screens/administration/add_mission_page.dart';
import 'package:boitex_info_app/screens/administration/mission_details_page.dart';
// ✅ ADDED: Import for Mission History Page
import 'package:boitex_info_app/screens/administration/mission_history_list_page.dart';

class ManageMissionsPage extends StatefulWidget {
  final String? serviceType;
  const ManageMissionsPage({super.key, this.serviceType});

  @override
  State<ManageMissionsPage> createState() => _ManageMissionsPageState();
}

class _ManageMissionsPageState extends State<ManageMissionsPage> {
  late Stream<QuerySnapshot> _missionsStream;

  @override
  void initState() {
    super.initState();
    Query query = FirebaseFirestore.instance.collection('missions');

    if (widget.serviceType != null) {
      query = query.where('serviceType', isEqualTo: widget.serviceType);
    }

    // ✅ CHANGED: This query now only fetches ACTIVE missions
    _missionsStream = query
        .where('status', whereIn: ['Planifiée', 'En Cours'])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Planifiée': return Colors.orange;
      case 'En Cours': return Colors.blue;
      case 'Terminée': return Colors.green;
      case 'Annulée': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _getStatusChip(String status) {
    return Chip(
      label: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: _getStatusColor(status),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.serviceType == null
            ? 'Missions Actives' // ✅ CHANGED: Title updated for clarity
            : 'Missions Actives - ${widget.serviceType}'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFF00BCD4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // ✅ ADDED: History Action Button
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: "Historique des Missions",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MissionHistoryListPage(
                    // ✅ FIXED: Provide a default value if widget.serviceType is null
                    serviceType: widget.serviceType ?? 'Service Technique',
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _missionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text('Aucune mission active', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                ],
              ),
            );
          }

          final missions = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: missions.length,
            itemBuilder: (context, index) {
              final mission = Mission.fromFirestore(missions[index]);
              final formattedStart = DateFormat('dd/MM/yyyy').format(mission.startDate);
              final formattedEnd = DateFormat('dd/MM/yyyy').format(mission.endDate);

              final destinationsText = mission.destinations.isEmpty
                  ? 'N/A'
                  : mission.destinations.length == 1
                  ? mission.destinations[0]
                  : mission.destinations.join(' → ');

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MissionDetailsPage(mission: mission),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.assignment, color: Colors.purple.shade700),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${mission.missionCode} - ${mission.title}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mission.serviceType,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            _getStatusChip(mission.status),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: Colors.red.shade400),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                destinationsText,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.blue.shade400),
                            const SizedBox(width: 4),
                            Text(
                              'Du $formattedStart au $formattedEnd',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        if (mission.assignedTechniciansNames.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.people, size: 16, color: Colors.green.shade400),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  mission.assignedTechniciansNames.join(', '),
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddMissionPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle Mission'),
        backgroundColor: Colors.purple,
      ),
    );
  }
}